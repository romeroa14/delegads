<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PageAccessRequest extends Model
{
    protected $table = 'page_access_requests';

    protected $guarded = [];

    protected $casts = [
        'accepted_at' => 'datetime',
        'created_at' => 'datetime',
    ];

    public $timestamps = false;

    public function lead()
    {
        return $this->belongsTo(Lead::class, 'lead_id');
    }
}
