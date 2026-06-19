<?php

namespace App\Filament\Resources\AdvertisingPlanResource\Pages;

use App\Filament\Resources\AdvertisingPlanResource;
use Filament\Actions;
use Filament\Resources\Pages\ViewRecord;

class ViewAdvertisingPlan extends ViewRecord
{
    protected static string $resource = AdvertisingPlanResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\EditAction::make(),
        ];
    }
}
