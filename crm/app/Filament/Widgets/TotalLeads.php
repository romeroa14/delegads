<?php

namespace App\Filament\Widgets;

use App\Models\Lead;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class TotalLeads extends BaseWidget
{
    protected static ?int $sort = 1;

    protected function getStats(): array
    {
        $total = Lead::count();
        $hot = Lead::where('lead_level', 'hot')->count();
        $newToday = Lead::whereDate('created_at', today())->count();
        $active = Lead::where('stage', 'active')->count();

        return [
            Stat::make('Total Leads', number_format($total))
                ->description('All time')
                ->descriptionIcon('heroicon-m-user-group')
                ->color('primary')
                ->extraAttributes([
                    'class' => 'cursor-pointer',
                ]),

            Stat::make('Hot Leads', number_format($hot))
                ->description('High intent')
                ->descriptionIcon('heroicon-m-fire')
                ->color('danger'),

            Stat::make('New Today', number_format($newToday))
                ->description('Created today')
                ->descriptionIcon('heroicon-m-sparkles')
                ->color('info'),

            Stat::make('Active Clients', number_format($active))
                ->description('Currently active')
                ->descriptionIcon('heroicon-m-check-circle')
                ->color('success'),
        ];
    }
}
