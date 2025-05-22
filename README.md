# Laravel Todo API

This is a Laravel-based API that provides the same functionality as the Next.js Server Actions Todo application.

## API Endpoints

- `GET /api/todos` - Get all todos
- `POST /api/todos` - Create a new todo
- `PUT /api/todos/{id}/toggle` - Toggle todo completion status
- `DELETE /api/todos/{id}` - Delete a todo

## Setup Instructions

1. Clone this repository
2. Run `docker-compose up -d`
3. Enter the container: `docker-compose exec app bash`
4. Install dependencies: `composer install`
5. Copy the environment file: `cp .env.example .env`
6. Generate application key: `php artisan key:generate`
7. Run migrations: `php artisan migrate`

The API will be available at `http://localhost:8000/api/todos`