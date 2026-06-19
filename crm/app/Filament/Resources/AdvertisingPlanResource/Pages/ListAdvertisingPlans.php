<?php

namespace App\Filament\Resources\AdvertisingPlanResource\Pages;

use App\Filament\Resources\AdvertisingPlanResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListAdvertisingPlans extends ListRecords
{
    protected static string $resource = AdvertisingPlanResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}
