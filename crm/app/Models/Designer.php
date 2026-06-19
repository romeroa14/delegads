<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Designer extends Model
{
    protected $table = 'designers';

    protected $guarded = [];

    protected $casts = [
        'specialties' => 'array',
        'is_active' => 'boolean',
        'rating' => 'decimal:2',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function designJobs(): HasMany
    {
        return $this->hasMany(DesignJob::class, 'designer_id');
    }
}
