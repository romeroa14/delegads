<?php

namespace App\Filament\Resources\DesignJobResource\Pages;

use App\Filament\Resources\DesignJobResource;
use Filament\Actions;
use Filament\Resources\Pages\ViewRecord;

class ViewDesignJob extends ViewRecord
{
    protected static string $resource = DesignJobResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\EditAction::make(),
        ];
    }
}
