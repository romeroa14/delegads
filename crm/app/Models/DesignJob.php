<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DesignJob extends Model
{
    protected $table = 'design_jobs';

    protected $guarded = [];

    protected $casts = [
        'style_preferences' => 'array',
        'price' => 'decimal:2',
        'fallback_at' => 'datetime',
        'approved_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function lead(): BelongsTo
    {
        return $this->belongsTo(Lead::class, 'lead_id');
    }

    public function designer(): BelongsTo
    {
        return $this->belongsTo(Designer::class);
    }
}
