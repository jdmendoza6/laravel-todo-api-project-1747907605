<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class HealthController extends Controller
{
    public function check()
    {
        try {
            // Check database connection
            DB::connection()->getPdo();
            
            return response()->json([
                'status' => 'healthy',
                'message' => 'Application is running correctly',
                'timestamp' => now()->toIso8601String(),
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 'unhealthy',
                'message' => 'Database connection failed',
                'error' => $e->getMessage(),
                'timestamp' => now()->toIso8601String(),
            ], 503);
        }
    }
}
