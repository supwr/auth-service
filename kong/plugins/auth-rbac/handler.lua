package.cpath = package.cpath .. ";/usr/local/openresty/lualib/?.so"

local hmac = require "resty.openssl.hmac"
local pgmoon = require "pgmoon"

local jwt_secret = "sua_chave_secreta_jwt_super_segura"

local _M = {
  PRIORITY = 1000,
  VERSION = "1.0.0",
}

local function problem(status, title, detail)
  return kong.response.exit(status, {
    type = "about:blank",
    title = title,
    status = status,
    detail = detail,
  }, {
    ["Content-Type"] = "application/problem+json",
  })
end

local function is_blank(value)
  return value == nil or value == ""
end

local function base64url_encode(value)
  return ngx.encode_base64(value)
    :gsub("%+", "-")
    :gsub("/", "_")
    :gsub("=", "")
end

local function sign_jwt(claims)
  local header_token = base64url_encode('{"alg":"HS256","typ":"JWT"}')
  local claims_token = base64url_encode(string.format(
    '{"iss":"kong","sub":"%s","role":"%s","iat":%d,"exp":%d}',
    claims.sub,
    claims.role,
    claims.iat,
    claims.exp
  ))
  local signing_input = header_token .. "." .. claims_token

  local signer, err = hmac.new(jwt_secret, "sha256")
  if not signer then
    return nil, err
  end

  local ok, update_err = signer:update(signing_input)
  if not ok then
    return nil, update_err
  end

  local signature, final_err = signer:final()
  if not signature then
    return nil, final_err
  end

  return signing_input .. "." .. base64url_encode(signature)
end

local function database_config()
  return {
    host = os.getenv("KONG_PG_HOST") or "kong-database",
    port = tonumber(os.getenv("KONG_PG_PORT") or "5432"),
    user = os.getenv("KONG_PG_USER") or "kong",
    password = os.getenv("KONG_PG_PASSWORD") or "kong-pwd",
    database = os.getenv("KONG_PG_DATABASE") or "kong",
    ssl = false,
  }
end

local function get_user(username, password)
  local pg = pgmoon.new(database_config())
  local ok, err = pg:connect()
  if not ok then
    return nil, err
  end

  local query = "SELECT id::text AS id, role FROM auth_users WHERE username = "
    .. pg:escape_literal(username)
    .. " AND password_hash = crypt("
    .. pg:escape_literal(password)
    .. ", password_hash) LIMIT 1"

  local rows, query_err = pg:query(query)
  pg:keepalive()

  if not rows then
    return nil, query_err
  end

  return rows[1]
end

local function login()
  local payload, body_err = kong.request.get_body()
  if body_err or not payload then
    return problem(400, "Bad Request", "Invalid JSON body.")
  end

  local username = payload.username
  local password = payload.password

  if is_blank(username) or is_blank(password) then
    return problem(400, "Bad Request", "Username and password are required.")
  end

  local user, user_err = get_user(username, password)
  if user_err then
    kong.log.err("auth-rbac database error: ", user_err)
    return problem(500, "Internal Server Error", "Unable to authenticate user.")
  end

  if not user then
    return problem(401, "Unauthorized", "Invalid credentials.")
  end

  local now = ngx.time()
  local token, sign_err = sign_jwt({
    iss = "kong",
    sub = user.id,
    role = user.role,
    iat = now,
    exp = now + 3600,
  })

  if not token then
    kong.log.err("auth-rbac jwt error: ", sign_err)
    return problem(500, "Internal Server Error", "Unable to generate token.")
  end

  return kong.response.exit(200, {
    access_token = token,
    token_type = "Bearer",
    expires_in = 3600,
  }, {
    ["Content-Type"] = "application/json",
  })
end

local function authenticate_request()
  local auth_header = kong.request.get_header("authorization")
  if is_blank(auth_header) then
    return problem(401, "Unauthorized", "Authorization header is required.")
  end

  local token = auth_header:gsub("^Bearer%s+", "")
  local jwt_decoder = require "kong.plugins.jwt.jwt_parser"
  local jwt, jwt_err = jwt_decoder:new(token)
  if not jwt then
    kong.log.err("auth-rbac jwt parse error: ", jwt_err)
    return problem(401, "Unauthorized", "Invalid token.")
  end

  if not jwt:verify_signature(jwt_secret) then
    return problem(401, "Unauthorized", "Invalid token signature.")
  end

  local claims_ok = jwt:verify_registered_claims({ "exp" })
  if not claims_ok then
    return problem(401, "Unauthorized", "Token expired or invalid.")
  end

  local user_id = jwt.claims.sub
  local roles = jwt.claims.role

  if is_blank(user_id) or is_blank(roles) then
    return problem(401, "Unauthorized", "Token is missing identity claims.")
  end

  if type(roles) == "table" then
    roles = table.concat(roles, ",")
  end

  kong.service.request.set_header("X-User-ID", tostring(user_id))
  kong.service.request.set_header("X-User-Roles", tostring(roles))
end

function _M:access()
  if kong.request.get_method() ~= "POST" then
    if kong.request.get_path():find("^/api/v1/appointments/") then
      return authenticate_request()
    end

    return
  end

  if kong.request.get_path() ~= "/api/v1/auth/login" then
    if kong.request.get_path():find("^/api/v1/appointments/") then
      return authenticate_request()
    end

    return
  end

  return login()
end

return _M
