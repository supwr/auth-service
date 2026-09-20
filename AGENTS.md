# Agent Guidelines & Context - auth-service

## Project Overview
Serviço de autenticação e autorização (`auth-service`) atuando como um microsserviço satélite na arquitetura do sistema. Suas responsabilidades principais são o cadastro, gerenciamento de usuários e validação de acessos. O ponto de entrada principal do ecossistema é um API Gateway Kong, que delega ao `auth-service` a validação das credenciais e a emissão de tokens JWT contendo as *roles* cadastradas.

## Architecture
- **Clean Architecture:** Desacoplamento estrito entre camadas (Domain, Use Cases, Adapters/Controllers, Infrastructure).
- O domínio principal de negócio pertence aos outros microsserviços do ecossistema; o `auth-service` opera exclusivamente como um serviço de suporte à segurança/autenticação.

## Error Handling & Responses
- **Padrão RFC 7807 (ProblemDetail):** Todas as respostas de erro da aplicação (erros de validação, exceções de domínio, erros de autorização e exceções não tratadas) devem seguir obrigatoriamente o padrão **`ProblemDetail` (RFC 7807)**.

## Tech Stack
- **Linguagem / Framework:** Java e Spring Boot (seguir estritamente as mesmas versões do repositório base `restaurant-manager-clean-arch`).
- **Banco de Dados:** H2 Database (em memória/arquivo por se tratar de um serviço satélite).
- **Segurança:** Spring Security + JWT (JSON Web Token).

## Coding & Behavior Standards
- **Sem Comentários de Agentes:** Não adicione comentários no código informando que o trecho foi gerado ou alterado por IA.
- **Padrão de Código:** Manter coesão, imutabilidade no domínio quando aplicável, e isolamento total das regras de negócio em relação a frameworks externos.
- **Testes:**
  - Seguir rigorousamente o mesmo padrão de testes unitários e de integração estabelecido no repositório base.
  - Toda nova funcionalidade deve obrigatoriamente acompanhar seus respectivos testes unitários e/ou de integração.

## Git & Commit Rules
- **Proibido Commitar Arquivos de Agentes:** Sob hipótese alguma inclua ou trackeie arquivos de suporte aos agentes (como `AGENTS.md`, `.copilot-instructions.md`, arquivos de `skills` ou similares) nos commits.
- **Confirmação Obrigatória:** Qualquer arquivo que não pertença estritamente ao código-fonte ou recursos da aplicação (`src/`, `pom.xml`/`build.gradle`, `.gitignore`, etc.) deve passar por confirmação do desenvolvedor antes de ser commitado.