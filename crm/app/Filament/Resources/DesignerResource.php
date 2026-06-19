<?php

namespace App\Filament\Resources;

use App\Filament\Resources\DesignerResource\Pages;
use App\Models\Designer;
use BackedEnum;
use Filament\Actions;
use Filament\Forms;
use Filament\Resources\Resource;
use Filament\Schemas;
use Filament\Schemas\Schema;
use Filament\Tables;
use Filament\Tables\Table;
use UnitEnum;

class DesignerResource extends Resource
{
    protected static ?string $model = Designer::class;

    protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-user-circle';

    protected static string|UnitEnum|null $navigationGroup = 'Design Operations';

    protected static ?string $modelLabel = 'Designer';

    protected static ?string $pluralModelLabel = 'Designers';

    protected static ?int $navigationSort = 2;

    public static function form(Schema $schema): Schema
    {
        return $schema
            ->schema([
                Schemas\Components\Section::make('Profile')
                    ->columns(2)
                    ->schema([
                        Forms\Components\TextInput::make('name')
                            ->required()
                            ->maxLength(255),

                        Forms\Components\TextInput::make('email')
                            ->email()
                            ->maxLength(255),

                        Forms\Components\TextInput::make('phone')
                            ->tel()
                            ->maxLength(50),

                        Forms\Components\TextInput::make('whatsapp_number')
                            ->label('WhatsApp Number')
                            ->tel()
                            ->maxLength(50),
                    ]),

                Schemas\Components\Section::make('Capacity & Pricing')
                    ->columns(3)
                    ->schema([
                        Forms\Components\Toggle::make('is_active')
                            ->label('Active')
                            ->default(true)
                            ->inline(false),

                        Forms\Components\TextInput::make('current_workload')
                            ->label('Current Workload')
                            ->numeric()
                            ->default(0)
                            ->disabled(),

                        Forms\Components\TextInput::make('max_workload')
                            ->label('Max Workload')
                            ->numeric()
                            ->default(3)
                            ->required(),

                        Forms\Components\TextInput::make('rating')
                            ->numeric()
                            ->step(0.01)
                            ->minValue(0)
                            ->maxValue(5)
                            ->default(5.00)
                            ->suffix('/ 5'),
                    ]),

                Schemas\Components\Section::make('Specialties')
                    ->schema([
                        Forms\Components\TagsInput::make('specialties')
                            ->label('Specialties')
                            ->placeholder('Add a specialty and press Enter')
                            ->suggestions([
                                'logo',
                                'social media',
                                'print',
                                'branding',
                                'flyers',
                                'video',
                                'illustrations',
                            ]),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->sortable(),

                Tables\Columns\TextColumn::make('name')
                    ->searchable()
                    ->sortable()
                    ->weight('medium'),

                Tables\Columns\TextColumn::make('email')
                    ->searchable()
                    ->placeholder('—')
                    ->icon('heroicon-m-envelope'),

                Tables\Columns\TextColumn::make('whatsapp_number')
                    ->label('WhatsApp')
                    ->placeholder('—')
                    ->icon('heroicon-m-phone'),

                Tables\Columns\TextColumn::make('current_workload')
                    ->label('Workload')
                    ->formatStateUsing(fn ($record) => "{$record->current_workload} / {$record->max_workload}")
                    ->badge()
                    ->color(fn ($record) => $record->current_workload >= $record->max_workload
                        ? 'danger'
                        : ($record->current_workload > 0 ? 'warning' : 'success')),

                Tables\Columns\TextColumn::make('rating')
                    ->numeric(2)
                    ->suffix(' / 5')
                    ->icon('heroicon-m-star')
                    ->sortable(),

                Tables\Columns\IconColumn::make('is_active')
                    ->label('Active')
                    ->boolean(),

                Tables\Columns\TextColumn::make('specialties')
                    ->badge()
                    ->separator(',')
                    ->placeholder('—')
                    ->toggleable(),
            ])
            ->defaultSort('name')
            ->filters([
                Tables\Filters\TernaryFilter::make('is_active')
                    ->label('Active Status')
                    ->placeholder('All designers')
                    ->trueLabel('Active only')
                    ->falseLabel('Inactive only'),
            ])
            ->actions([
                Actions\ViewAction::make(),
                Actions\EditAction::make(),
                Actions\DeleteAction::make(),
            ])
            ->bulkActions([
                Actions\BulkActionGroup::make([
                    Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListDesigners::route('/'),
            'create' => Pages\CreateDesigner::route('/create'),
            'view' => Pages\ViewDesigner::route('/{record}'),
            'edit' => Pages\EditDesigner::route('/{record}/edit'),
        ];
    }
}
