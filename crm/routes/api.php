<?php

use App\Http\Controllers\Api\CampaignController;
use App\Http\Controllers\Api\DesignJobController;
use App\Http\Controllers\Api\LeadController;
use App\Http\Controllers\Api\MetricsController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

Route::middleware('auth:sanctum')->prefix('v1')->group(function () {
    // Leads
    Route::get('/leads', [LeadController::class, 'index']);
    Route::get('/leads/{id}', [LeadController::class, 'show']);

    // Design jobs
    Route::get('/design-jobs', [DesignJobController::class, 'index']);
    Route::get('/design-jobs/{id}', [DesignJobController::class, 'show']);

    // Campaigns
    Route::get('/campaigns', [CampaignController::class, 'index']);
    Route::get('/campaigns/{id}', [CampaignController::class, 'show']);

    // Aggregated metrics for dashboards (mobile app)
    Route::get('/metrics', [MetricsController::class, 'index']);
});
