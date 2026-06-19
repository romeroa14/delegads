<?php

namespace App\Filament\Resources\DesignerResource\Pages;

use App\Filament\Resources\DesignerResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListDesigners extends ListRecords
{
    protected static string $resource = DesignerResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}
