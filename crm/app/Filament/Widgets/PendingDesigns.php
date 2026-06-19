<?php

namespace App\Filament\Widgets;

use App\Models\DesignJob;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class PendingDesigns extends BaseWidget
{
    protected static ?int $sort = 3;

    protected function getStats(): array
    {
        $pending = DesignJob::whereIn('status', ['requested', 'in_progress'])->count();
        $review = DesignJob::where('status', 'review')->count();
        $approved = DesignJob::where('status', 'approved')->count();
        $rejected = DesignJob::where('status', 'rejected')->count();

        return [
            Stat::make('In Progress', number_format($pending))
                ->description('Requested + in progress')
                ->descriptionIcon('heroicon-m-clock')
                ->color('warning'),

            Stat::make('In Review', number_format($review))
                ->description('Awaiting client approval')
                ->descriptionIcon('heroicon-m-eye')
                ->color('info'),

            Stat::make('Approved', number_format($approved))
                ->description('Successfully delivered')
                ->descriptionIcon('heroicon-m-check-badge')
                ->color('success'),

            Stat::make('Rejected', number_format($rejected))
                ->description('Need rework')
                ->descriptionIcon('heroicon-m-x-circle')
                ->color('danger'),
        ];
    }
}
