<?php

namespace App\Filament\Widgets;

use App\Models\Lead;
use Filament\Widgets\ChartWidget;

class ConversionFunnel extends ChartWidget
{
    protected static ?string $heading = 'Conversion Funnel';

    protected static ?int $sort = 5;

    protected static ?string $maxHeight = '320px';

    protected function getData(): array
    {
        // Funnel from top-of-funnel to active client
        $new = Lead::whereIn('stage', ['new', 'initial'])->count();
        $interested = Lead::whereIn('stage', ['interested', 'pricing_discussion'])->count();
        $ready = Lead::whereIn('stage', ['ready_to_buy', 'payment_pending'])->count();
        $onboarding = Lead::where('stage', 'onboarding')->count();
        $active = Lead::where('stage', 'active')->count();

        $labels = ['New / Initial', 'Interested / Pricing', 'Ready / Payment', 'Onboarding', 'Active'];
        $values = [$new, $interested, $ready, $onboarding, $active];

        return [
            'datasets' => [
                [
                    'label' => 'Leads',
                    'data' => $values,
                    'backgroundColor' => [
                        'rgba(148, 163, 184, 0.7)',
                        'rgba(14, 165, 233, 0.7)',
                        'rgba(245, 158, 11, 0.7)',
                        'rgba(16, 185, 129, 0.7)',
                        'rgba(34, 197, 94, 0.9)',
                    ],
                    'borderColor' => [
                        'rgb(148, 163, 184)',
                        'rgb(14, 165, 233)',
                        'rgb(245, 158, 11)',
                        'rgb(16, 185, 129)',
                        'rgb(34, 197, 94)',
                    ],
                    'borderWidth' => 1,
                ],
            ],
            'labels' => $labels,
        ];
    }

    protected function getType(): string
    {
        return 'bar';
    }

    protected function getOptions(): array
    {
        return [
            'indexAxis' => 'y',
            'plugins' => [
                'legend' => [
                    'display' => false,
                ],
            ],
            'scales' => [
                'x' => [
                    'beginAtZero' => true,
                    'ticks' => [
                        'precision' => 0,
                    ],
                ],
            ],
            'maintainAspectRatio' => false,
        ];
    }
}
