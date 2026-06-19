<?php

namespace App\Filament\Resources\DesignJobResource\Pages;

use App\Filament\Resources\DesignJobResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListDesignJobs extends ListRecords
{
    protected static string $resource = DesignJobResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}
