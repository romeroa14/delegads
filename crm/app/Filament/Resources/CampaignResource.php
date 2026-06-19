<?php

namespace App\Filament\Resources;

use App\Filament\Resources\CampaignResource\Pages;
use App\Models\Campaign;
use BackedEnum;
use Filament\Actions;
use Filament\Forms;
use Filament\Resources\Resource;
use Filament\Schemas;
use Filament\Schemas\Schema;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Filters\SelectFilter;
use UnitEnum;

class CampaignResource extends Resource
{
    protected static ?string $model = Campaign::class;

    protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-megaphone';

    protected static string|UnitEnum|null $navigationGroup = 'Marketing';

    protected static ?string $modelLabel = 'Facebook Campaign';

    protected static ?string $pluralModelLabel = 'Facebook Campaigns';

    protected static ?int $navigationSort = 1;

    public static function form(Schema $schema): Schema
    {
        return $schema
            ->schema([
                Schemas\Components\Section::make('Campaign')
                    ->columns(2)
                    ->schema([
                        Forms\Components\TextInput::make('campaign_id')
                            ->label('Meta Campaign ID')
                            ->required()
                            ->maxLength(255),

                        Forms\Components\TextInput::make('campaign_name')
                            ->label('Name')
                            ->required()
                            ->maxLength(255),

                        Forms\Components\Select::make('campaign_status')
                            ->label('Status')
                            ->options([
                                'ACTIVE' => 'Active',
                                'PAUSED' => 'Paused',
                                'DELETED' => 'Deleted',
                                'ARCHIVED' => 'Archived',
                                'IN_REVIEW' => 'In Review',
                            ])
                            ->required()
                            ->default('ACTIVE')
                            ->native(false),

                        Forms\Components\Select::make('facebook_account_id')
                            ->label('Facebook Account')
                            ->relationship('facebookAccount', 'name')
                            ->searchable()
                            ->preload()
                            ->required(),
                    ]),

                Schemas\Components\Section::make('Date Range')
                    ->columns(3)
                    ->schema([
                        Forms\Components\DatePicker::make('date_start')
                            ->label('Start Date'),

                        Forms\Components\DatePicker::make('date_stop')
                            ->label('End Date'),

                        Forms\Components\TextInput::make('date_range')
                            ->label('Range Label')
                            ->maxLength(255)
                            ->placeholder('e.g. 2026-06-01_2026-06-30'),
                    ]),

                Schemas\Components\Section::make('Timestamps')
                    ->columns(2)
                    ->collapsed()
                    ->schema([
                        Forms\Components\DateTimePicker::make('last_updated')
                            ->disabled(),

                        Forms\Components\DateTimePicker::make('created_at')
                            ->disabled(),

                        Forms\Components\DateTimePicker::make('updated_at')
                            ->disabled(),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('campaign_id')
                    ->label('Meta ID')
                    ->searchable()
                    ->copyable()
                    ->limit(20),

                Tables\Columns\TextColumn::make('campaign_name')
                    ->label('Name')
                    ->searchable()
                    ->sortable()
                    ->weight('medium')
                    ->limit(40),

                Tables\Columns\TextColumn::make('campaign_status')
                    ->label('Status')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'ACTIVE' => 'success',
                        'PAUSED' => 'warning',
                        'DELETED' => 'danger',
                        'ARCHIVED' => 'gray',
                        'IN_REVIEW' => 'info',
                        default => 'gray',
                    }),

                Tables\Columns\TextColumn::make('facebookAccount.name')
                    ->label('Account')
                    ->placeholder('—')
                    ->toggleable(),

                Tables\Columns\TextColumn::make('date_start')
                    ->label('Start')
                    ->date('Y-m-d')
                    ->placeholder('—')
                    ->sortable(),

                Tables\Columns\TextColumn::make('date_stop')
                    ->label('End')
                    ->date('Y-m-d')
                    ->placeholder('—')
                    ->sortable(),

                Tables\Columns\TextColumn::make('last_updated')
                    ->label('Last Update')
                    ->dateTime('Y-m-d H:i')
                    ->placeholder('—')
                    ->since()
                    ->sortable(),
            ])
            ->defaultSort('last_updated', 'desc')
            ->filters([
                SelectFilter::make('campaign_status')
                    ->label('Status')
                    ->options([
                        'ACTIVE' => 'Active',
                        'PAUSED' => 'Paused',
                        'DELETED' => 'Deleted',
                        'ARCHIVED' => 'Archived',
                        'IN_REVIEW' => 'In Review',
                    ])
                    ->multiple(),
            ])
            ->actions([
                Actions\ViewAction::make(),
                Actions\EditAction::make(),
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
            'index' => Pages\ListCampaigns::route('/'),
            'create' => Pages\CreateCampaign::route('/create'),
            'view' => Pages\ViewCampaign::route('/{record}'),
            'edit' => Pages\EditCampaign::route('/{record}/edit'),
        ];
    }

    public static function getNavigationBadge(): ?string
    {
        $count = static::getModel()::where('campaign_status', 'ACTIVE')->count();
        return $count ?: null;
    }
}
