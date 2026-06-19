<?php

namespace App\Filament\Resources\DesignJobResource\Pages;

use App\Filament\Resources\DesignJobResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditDesignJob extends EditRecord
{
    protected static string $resource = DesignJobResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\ViewAction::make(),
            Actions\DeleteAction::make(),
        ];
    }
}
