<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class TodoSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $now = Carbon::now();
        
        DB::table('todos')->insert([
            [
                'title' => 'Deploy to AWS ECS',
                'description' => 'Deploy the Laravel Todo API to AWS ECS using CloudFormation',
                'completed' => false,
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'title' => 'Configure CloudWatch Logs',
                'description' => 'Set up CloudWatch Logs for monitoring the application',
                'completed' => false,
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'title' => 'Set up CI/CD pipeline',
                'description' => 'Configure GitHub Actions for continuous deployment',
                'completed' => false,
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'title' => 'Implement HTTPS',
                'description' => 'Add HTTPS support using AWS Certificate Manager',
                'completed' => false,
                'created_at' => $now,
                'updated_at' => $now,
            ],
        ]);
    }
}
