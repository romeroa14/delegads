<?php

namespace App\Filament\Resources\DesignerResource\Pages;

use App\Filament\Resources\DesignerResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditDesigner extends EditRecord
{
    protected static string $resource = DesignerResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\ViewAction::make(),
            Actions\DeleteAction::make(),
        ];
    }
}
