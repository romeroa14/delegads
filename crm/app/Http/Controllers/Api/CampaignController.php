<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Campaign;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CampaignController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $perPage = min((int) $request->input('per_page', 25), 100);
        $perPage = max($perPage, 1);

        $query = Campaign::query()
            ->with('facebookAccount:id,name')
            ->select([
                'id', 'facebook_account_id', 'campaign_id', 'campaign_name',
                'campaign_status', 'date_start', 'date_stop', 'date_range',
                'last_updated', 'created_at', 'updated_at',
            ]);

        if ($status = $request->input('status')) {
            $query->where('campaign_status', $status);
        }

        $query->orderByDesc('last_updated');

        return response()->json($query->paginate($perPage));
    }

    public function show(string $id): JsonResponse
    {
        $campaign = Campaign::with('facebookAccount:id,name')->findOrFail($id);

        return response()->json($campaign);
    }
}
