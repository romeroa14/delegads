<?php

namespace App\Filament\Resources;

use App\Filament\Resources\AdvertisingPlanResource\Pages;
use App\Models\AdvertisingPlan;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class AdvertisingPlanResource extends Resource
{
    protected static ?string $model = AdvertisingPlan::class;

    protected static ?string $navigationIcon = 'heroicon-o-currency-dollar';

    protected static ?string $navigationGroup = 'Marketing';

    protected static ?string $modelLabel = 'Advertising Plan';

    protected static ?string $pluralModelLabel = 'Advertising Plans';

    protected static ?int $navigationSort = 2;

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Plan')
                    ->columns(2)
                    ->schema([
                        Forms\Components\TextInput::make('plan_name')
                            ->required()
                            ->maxLength(255),

                        Forms\Components\Toggle::make('is_active')
                            ->label('Active')
                            ->default(true)
                            ->inline(false),

                        Forms\Components\Textarea::make('description')
                            ->rows(3)
                            ->columnSpanFull(),
                    ]),

                Forms\Components\Section::make('Pricing')
                    ->columns(3)
                    ->schema([
                        Forms\Components\TextInput::make('daily_budget')
                            ->label('Daily Budget')
                            ->numeric()
                            ->prefix('$')
                            ->required(),

                        Forms\Components\TextInput::make('duration_days')
                            ->label('Duration (days)')
                            ->numeric()
                            ->required(),

                        Forms\Components\TextInput::make('total_budget')
                            ->label('Total Budget')
                            ->numeric()
                            ->prefix('$')
                            ->required(),

                        Forms\Components\TextInput::make('client_price')
                            ->label('Client Price')
                            ->numeric()
                            ->prefix('$')
                            ->required(),

                        Forms\Components\TextInput::make('profit_margin')
                            ->label('Profit Margin')
                            ->numeric()
                            ->prefix('$')
                            ->required(),

                        Forms\Components\TextInput::make('profit_percentage')
                            ->label('Profit %')
                            ->numeric()
                            ->suffix('%')
                            ->required(),
                    ]),

                Forms\Components\Section::make('Features')
                    ->schema([
                        Forms\Components\KeyValue::make('features')
                            ->label('Plan Features')
                            ->keyLabel('Feature')
                            ->valueLabel('Value')
                            ->addActionLabel('Add feature'),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('plan_name')
                    ->searchable()
                    ->sortable()
                    ->weight('medium'),

                Tables\Columns\TextColumn::make('daily_budget')
                    ->label('Daily')
                    ->money('USD')
                    ->sortable(),

                Tables\Columns\TextColumn::make('duration_days')
                    ->label('Days')
                    ->numeric()
                    ->suffix(' d')
                    ->sortable(),

                Tables\Columns\TextColumn::make('total_budget')
                    ->label('Total')
                    ->money('USD')
                    ->sortable(),

                Tables\Columns\TextColumn::make('client_price')
                    ->label('Price')
                    ->money('USD')
                    ->sortable(),

                Tables\Columns\TextColumn::make('profit_margin')
                    ->label('Profit')
                    ->money('USD')
                    ->sortable(),

                Tables\Columns\TextColumn::make('profit_percentage')
                    ->label('Margin')
                    ->numeric(2)
                    ->suffix('%')
                    ->sortable(),

                Tables\Columns\IconColumn::make('is_active')
                    ->label('Active')
                    ->boolean(),
            ])
            ->defaultSort('client_price', 'asc')
            ->filters([
                Tables\Filters\TernaryFilter::make('is_active')
                    ->label('Active')
                    ->placeholder('All plans')
                    ->trueLabel('Active only')
                    ->falseLabel('Inactive only'),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
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
            'index' => Pages\ListAdvertisingPlans::route('/'),
            'create' => Pages\CreateAdvertisingPlan::route('/create'),
            'view' => Pages\ViewAdvertisingPlan::route('/{record}'),
            'edit' => Pages\EditAdvertisingPlan::route('/{record}/edit'),
        ];
    }
}
