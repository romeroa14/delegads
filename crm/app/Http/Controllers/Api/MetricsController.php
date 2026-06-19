<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Campaign;
use App\Models\DesignJob;
use App\Models\Lead;
use Illuminate\Http\JsonResponse;

class MetricsController extends Controller
{
    /**
     * Aggregated metrics for mobile app dashboards.
     */
    public function index(): JsonResponse
    {
        $stages = [
            'new', 'initial', 'interested', 'pricing_discussion',
            'ready_to_buy', 'payment_pending', 'onboarding', 'active', 'cold',
        ];

        $leadsByStage = Lead::query()
            ->selectRaw('stage, COUNT(*) as count')
            ->whereIn('stage', $stages)
            ->groupBy('stage')
            ->pluck('count', 'stage');

        $leadsByLevel = Lead::query()
            ->selectRaw('lead_level, COUNT(*) as count')
            ->whereNotNull('lead_level')
            ->groupBy('lead_level')
            ->pluck('count', 'lead_level');

        $designByStatus = DesignJob::query()
            ->selectRaw('status, COUNT(*) as count')
            ->groupBy('status')
            ->pluck('count', 'status');

        $campaignsByStatus = Campaign::query()
            ->selectRaw('campaign_status, COUNT(*) as count')
            ->groupBy('campaign_status')
            ->pluck('count', 'campaign_status');

        return response()->json([
            'generated_at' => now()->toIso8601String(),
            'leads' => [
                'total' => Lead::count(),
                'new_today' => Lead::whereDate('created_at', today())->count(),
                'by_stage' => $leadsByStage,
                'by_level' => $leadsByLevel,
            ],
            'design_jobs' => [
                'total' => DesignJob::count(),
                'pending' => DesignJob::whereIn('status', ['requested', 'in_progress'])->count(),
                'revenue_total' => (float) DesignJob::where('status', 'approved')->sum('price'),
                'by_status' => $designByStatus,
            ],
            'campaigns' => [
                'total' => Campaign::count(),
                'active' => Campaign::where('campaign_status', 'ACTIVE')->count(),
                'paused' => Campaign::where('campaign_status', 'PAUSED')->count(),
                'by_status' => $campaignsByStatus,
            ],
        ]);
    }
}
