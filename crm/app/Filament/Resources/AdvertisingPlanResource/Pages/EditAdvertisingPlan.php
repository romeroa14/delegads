<?php

namespace App\Filament\Resources\AdvertisingPlanResource\Pages;

use App\Filament\Resources\AdvertisingPlanResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditAdvertisingPlan extends EditRecord
{
    protected static string $resource = AdvertisingPlanResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\ViewAction::make(),
            Actions\DeleteAction::make(),
        ];
    }
}
