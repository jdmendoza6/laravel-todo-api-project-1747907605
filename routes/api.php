<?php
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\TodoController;
use App\Http\Controllers\HealthController;

Route::get("/todos", [TodoController::class, "index"]);
Route::post("/todos", [TodoController::class, "store"]);
Route::put("/todos/{id}/toggle", [TodoController::class, "toggle"]);
Route::delete("/todos/{id}", [TodoController::class, "destroy"]);

// Health check endpoint for ALB and Kubernetes probes
Route::get('/health', [HealthController::class, 'check']);
