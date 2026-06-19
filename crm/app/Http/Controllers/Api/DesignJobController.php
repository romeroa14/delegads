<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DesignJob;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DesignJobController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $perPage = min((int) $request->input('per_page', 25), 100);
        $perPage = max($perPage, 1);

        $query = DesignJob::query()
            ->with(['lead:id,client_name,phone_number', 'designer:id,name'])
            ->select([
                'id', 'lead_id', 'type', 'status',
                'result_url', 'designer_id', 'price',
                'created_at', 'updated_at',
            ]);

        if ($status = $request->input('status')) {
            $query->where('status', $status);
        }

        if ($type = $request->input('type')) {
            $query->where('type', $type);
        }

        $query->orderByDesc('created_at');

        return response()->json($query->paginate($perPage));
    }

    public function show(string $id): JsonResponse
    {
        $job = DesignJob::with(['lead:id,client_name,phone_number', 'designer:id,name'])
            ->findOrFail($id);

        return response()->json($job);
    }
}
