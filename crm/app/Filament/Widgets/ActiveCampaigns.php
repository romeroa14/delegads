<?php

namespace App\Filament\Widgets;

use App\Models\Campaign;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class ActiveCampaigns extends BaseWidget
{
    protected static ?int $sort = 2;

    protected function getStats(): array
    {
        $active = Campaign::where('campaign_status', 'ACTIVE')->count();
        $paused = Campaign::where('campaign_status', 'PAUSED')->count();
        $total = Campaign::count();

        return [
            Stat::make('Active Campaigns', number_format($active))
                ->description('Running on Meta')
                ->descriptionIcon('heroicon-m-megaphone')
                ->color('success'),

            Stat::make('Paused', number_format($paused))
                ->description('Currently paused')
                ->descriptionIcon('heroicon-m-pause-circle')
                ->color('warning'),

            Stat::make('Total Campaigns', number_format($total))
                ->description('Tracked in CRM')
                ->descriptionIcon('heroicon-m-rectangle-stack')
                ->color('gray'),
        ];
    }
}
