<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AdvertisingPlan extends Model
{
    protected $table = 'advertising_plans';

    protected $guarded = [];

    protected $casts = [
        'daily_budget' => 'decimal:2',
        'total_budget' => 'decimal:2',
        'client_price' => 'decimal:2',
        'profit_margin' => 'decimal:2',
        'profit_percentage' => 'decimal:2',
        'is_active' => 'boolean',
        'features' => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];
}
