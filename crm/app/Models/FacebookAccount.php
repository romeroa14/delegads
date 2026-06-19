<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class FacebookAccount extends Model
{
    protected $table = 'facebook_accounts';

    protected $guarded = [];

    protected $casts = [
        'selected_campaign_ids' => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];
}
