<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Lead;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class LeadController extends Controller
{
    /**
     * List leads with optional filtering and pagination.
     */
    public function index(Request $request): JsonResponse
    {
        $perPage = min((int) $request->input('per_page', 25), 100);
        $perPage = max($perPage, 1);

        $query = Lead::query()
            ->select([
                'id', 'workspace_id', 'whatsapp_instance_id',
                'phone_number', 'client_name', 'intent', 'lead_level',
                'stage', 'confidence_score', 'bot_disabled',
                'last_human_intervention_at', 'page_id', 'page_name',
                'instagram_actor_id', 'selected_plan',
                'created_at', 'updated_at',
            ]);

        if ($stage = $request->input('stage')) {
            $query->where('stage', $stage);
        }

        if ($level = $request->input('lead_level')) {
            $query->where('lead_level', $level);
        }

        if ($intent = $request->input('intent')) {
            $query->where('intent', $intent);
        }

        if ($search = $request->input('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('client_name', 'ILIKE', "%{$search}%")
                  ->orWhere('phone_number', 'ILIKE', "%{$search}%");
            });
        }

        $query->orderByDesc('updated_at');

        return response()->json($query->paginate($perPage));
    }

    /**
     * Show a single lead with relationships.
     */
    public function show(string $id): JsonResponse
    {
        $lead = Lead::with([
            'designJobs:id,lead_id,type,status,price,created_at',
            'messages:id,tenant_lead_id,direction,content,platform,status,created_at',
            'pageAccessRequests:id,lead_id,page_id,page_name,status,created_at',
        ])->findOrFail($id);

        return response()->json($lead);
    }
}
