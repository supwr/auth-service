CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS auth_users (
    id UUID PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO auth_users (id, username, password_hash, role)
VALUES
    (gen_random_uuid(), 'doctor@example.com', crypt('123456', gen_salt('bf')), 'DOCTOR'),
    (gen_random_uuid(), 'nurse@example.com', crypt('123456', gen_salt('bf')), 'NURSE'),
    (gen_random_uuid(), 'patient@example.com', crypt('123456', gen_salt('bf')), 'PATIENT'),
    (gen_random_uuid(), 'admin@example.com', crypt('123456', gen_salt('bf')), 'ADMIN')
ON CONFLICT (username) DO UPDATE SET
    password_hash = EXCLUDED.password_hash,
    role = EXCLUDED.role;
