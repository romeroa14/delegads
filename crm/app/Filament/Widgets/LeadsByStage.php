<?php

namespace App\Filament\Widgets;

use App\Models\Lead;
use Filament\Widgets\ChartWidget;

class LeadsByStage extends ChartWidget
{
    protected ?string $heading = 'Leads by Pipeline Stage';

    protected static ?int $sort = 4;

    protected ?string $maxHeight = '300px';

    protected function getData(): array
    {
        $stages = [
            'new' => 'New',
            'initial' => 'Initial',
            'interested' => 'Interested',
            'pricing_discussion' => 'Pricing',
            'ready_to_buy' => 'Ready',
            'payment_pending' => 'Payment',
            'onboarding' => 'Onboarding',
            'active' => 'Active',
            'cold' => 'Cold',
        ];

        $data = [];
        $labels = [];
        $colors = [
            '#94a3b8', // new - gray
            '#0ea5e9', // initial - info
            '#3b82f6', // interested - blue
            '#f59e0b', // pricing - amber
            '#f97316', // ready - orange
            '#eab308', // payment - yellow
            '#10b981', // onboarding - emerald
            '#22c55e', // active - green
            '#64748b', // cold - slate
        ];

        $i = 0;
        foreach ($stages as $key => $label) {
            $count = Lead::where('stage', $key)->count();
            $data[] = $count;
            $labels[] = $label . " ({$count})";
            $i++;
        }

        return [
            'datasets' => [
                [
                    'label' => 'Leads',
                    'data' => $data,
                    'backgroundColor' => $colors,
                    'borderColor' => '#ffffff',
                    'borderWidth' => 2,
                ],
            ],
            'labels' => $labels,
        ];
    }

    protected function getType(): string
    {
        return 'doughnut';
    }

    protected function getOptions(): array
    {
        return [
            'plugins' => [
                'legend' => [
                    'position' => 'right',
                    'labels' => [
                        'font' => [
                            'size' => 11,
                        ],
                        'boxWidth' => 12,
                    ],
                ],
            ],
            'maintainAspectRatio' => false,
            'cutout' => '60%',
        ];
    }
}
