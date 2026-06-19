<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Lead extends Model
{
    protected $table = 'tenant_leads';

    protected $guarded = [];

    protected $casts = [
        'bot_disabled' => 'boolean',
        'confidence_score' => 'decimal:2',
        'ai_classification' => 'array',
        'last_human_intervention_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function workspace(): BelongsTo
    {
        return $this->belongsTo(Workspace::class);
    }

    public function whatsappInstance(): BelongsTo
    {
        return $this->belongsTo(WhatsappInstance::class);
    }

    public function messages(): HasMany
    {
        return $this->hasMany(Conversation::class, 'tenant_lead_id');
    }

    public function conversations(): HasMany
    {
        return $this->messages();
    }

    public function designJobs(): HasMany
    {
        return $this->hasMany(DesignJob::class, 'lead_id');
    }

    public function pageAccessRequests(): HasMany
    {
        return $this->hasMany(PageAccessRequest::class, 'lead_id');
    }

    public function agentHandoffs(): HasMany
    {
        return $this->hasMany(AgentHandoff::class, 'lead_id');
    }

    public function getDisplayNameAttribute(): string
    {
        return $this->client_name ?: $this->phone_number;
    }
}
