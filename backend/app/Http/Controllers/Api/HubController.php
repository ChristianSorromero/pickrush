<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Hub;
use Illuminate\Http\JsonResponse;

class HubController extends Controller
{
    public function index(): JsonResponse
    {
        $hubs = Hub::query()
            ->where('is_active', true)
            ->orderBy('name')
            ->get(['id', 'name', 'province']);

        return response()->json($hubs);
    }
}
