-- RDS Database Schema Setup for Laravel Todo API

-- Create the database if it doesn't exist
CREATE DATABASE IF NOT EXISTS laravel_todo_api;

-- Use the database
USE laravel_todo_api;

-- Create the todos table
CREATE TABLE IF NOT EXISTS todos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT NULL,
    completed BOOLEAN DEFAULT 0 NOT NULL,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL
);

-- Create the migrations table for Laravel
CREATE TABLE IF NOT EXISTS migrations (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    migration VARCHAR(255) NOT NULL,
    batch INT NOT NULL
);

-- Create the personal_access_tokens table for Laravel Sanctum
CREATE TABLE IF NOT EXISTS personal_access_tokens (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tokenable_type VARCHAR(255) NOT NULL,
    tokenable_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(255) NOT NULL,
    token VARCHAR(64) NOT NULL,
    abilities TEXT NULL,
    last_used_at TIMESTAMP NULL,
    expires_at TIMESTAMP NULL,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    UNIQUE KEY personal_access_tokens_token_unique (token),
    INDEX personal_access_tokens_tokenable_type_tokenable_id_index (tokenable_type, tokenable_id)
);

-- Insert sample todo items
INSERT INTO todos (title, completed, created_at, updated_at)
VALUES 
    ('Deploy to AWS ECS', 0, NOW(), NOW()),
    ('Configure CloudWatch Logs', 0, NOW(), NOW()),
    ('Set up CI/CD pipeline', 0, NOW(), NOW());
