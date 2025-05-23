<?php

namespace Database\Seeders;

use App\Models\Todo;
use Illuminate\Database\Seeder;

class TodoSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        Todo::create([
            'title' => 'Complete AWS deployment',
            'description' => 'Deploy Laravel Todo API to AWS ECS',
            'completed' => false,
        ]);

        Todo::create([
            'title' => 'Add authentication',
            'description' => 'Implement user authentication for the API',
            'completed' => false,
        ]);

        Todo::create([
            'title' => 'Write tests',
            'description' => 'Add unit and feature tests for the API',
            'completed' => false,
        ]);
    }
}
