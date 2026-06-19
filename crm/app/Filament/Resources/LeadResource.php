<?php

namespace App\Filament\Resources;

use App\Filament\Resources\LeadResource\Pages;
use App\Models\Lead;
use BackedEnum;
use Filament\Actions;
use Filament\Forms;
use Filament\Resources\Resource;
use Filament\Schemas;
use Filament\Schemas\Schema;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Filters\SelectFilter;
use Filament\Support\Colors\Color;
use UnitEnum;

class LeadResource extends Resource
{
    protected static ?string $model = Lead::class;

    protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-user-group';

    protected static string|UnitEnum|null $navigationGroup = 'Sales Pipeline';

    protected static ?string $modelLabel = 'Lead';

    protected static ?string $pluralModelLabel = 'Leads';

    protected static ?int $navigationSort = 1;

    public static function form(Schema $schema): Schema
    {
        return $schema
            ->schema([
                Schemas\Components\Section::make('Contact Information')
                    ->columns(2)
                    ->schema([
                        Forms\Components\TextInput::make('client_name')
                            ->label('Client Name')
                            ->maxLength(255)
                            ->columnSpan(1),

                        Forms\Components\TextInput::make('phone_number')
                            ->label('Phone Number')
                            ->tel()
                            ->required()
                            ->maxLength(255)
                            ->columnSpan(1),

                        Forms\Components\TextInput::make('workspace_id')
                            ->label('Workspace ID')
                            ->numeric()
                            ->required()
                            ->columnSpan(1),

                        Forms\Components\TextInput::make('whatsapp_instance_id')
                            ->label('WhatsApp Instance ID')
                            ->numeric()
                            ->columnSpan(1),
                    ]),

                Schemas\Components\Section::make('Pipeline Stage')
                    ->columns(3)
                    ->schema([
                        Forms\Components\Select::make('stage')
                            ->options([
                                'new' => 'New',
                                'initial' => 'Initial Contact',
                                'interested' => 'Interested',
                                'pricing_discussion' => 'Pricing Discussion',
                                'ready_to_buy' => 'Ready to Buy',
                                'payment_pending' => 'Payment Pending',
                                'onboarding' => 'Onboarding',
                                'active' => 'Active Client',
                                'cold' => 'Cold',
                            ])
                            ->required()
                            ->default('new')
                            ->native(false),

                        Forms\Components\Select::make('intent')
                            ->options([
                                'ads' => 'Ads',
                                'social_management' => 'Social Management',
                                'both' => 'Both',
                                'unclear' => 'Unclear',
                            ])
                            ->native(false),

                        Forms\Components\Select::make('lead_level')
                            ->label('Lead Level')
                            ->options([
                                'hot' => 'Hot',
                                'warm' => 'Warm',
                                'cold' => 'Cold',
                            ])
                            ->native(false),

                        Forms\Components\TextInput::make('confidence_score')
                            ->label('AI Confidence')
                            ->numeric()
                            ->step(0.01)
                            ->minValue(0)
                            ->maxValue(100)
                            ->suffix('%'),

                        Forms\Components\TextInput::make('selected_plan')
                            ->label('Selected Plan')
                            ->maxLength(100),

                        Forms\Components\Toggle::make('bot_disabled')
                            ->label('Bot Disabled')
                            ->helperText('Disable automated bot responses for this lead')
                            ->inline(false),
                    ]),

                Schemas\Components\Section::make('Facebook / Instagram')
                    ->columns(2)
                    ->collapsed()
                    ->schema([
                        Forms\Components\TextInput::make('page_id')
                            ->label('Facebook Page ID')
                            ->maxLength(255),

                        Forms\Components\TextInput::make('page_name')
                            ->label('Facebook Page Name')
                            ->maxLength(255),

                        Forms\Components\TextInput::make('instagram_actor_id')
                            ->label('Instagram Actor ID')
                            ->maxLength(255),
                    ]),

                Schemas\Components\Section::make('Timestamps')
                    ->columns(2)
                    ->collapsed()
                    ->schema([
                        Forms\Components\DateTimePicker::make('created_at')
                            ->disabled()
                            ->dehydrated(false),

                        Forms\Components\DateTimePicker::make('updated_at')
                            ->disabled()
                            ->dehydrated(false),

                        Forms\Components\DateTimePicker::make('last_human_intervention_at')
                            ->label('Last Human Intervention')
                            ->disabled()
                            ->dehydrated(false),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label('ID')
                    ->sortable()
                    ->searchable(),

                Tables\Columns\TextColumn::make('client_name')
                    ->label('Client')
                    ->searchable()
                    ->sortable()
                    ->weight('medium')
                    ->placeholder('—'),

                Tables\Columns\TextColumn::make('phone_number')
                    ->label('Phone')
                    ->searchable()
                    ->icon('heroicon-m-phone')
                    ->copyable(),

                Tables\Columns\TextColumn::make('stage')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'new' => 'gray',
                        'initial' => 'info',
                        'interested' => 'info',
                        'pricing_discussion' => 'warning',
                        'ready_to_buy' => 'warning',
                        'payment_pending' => 'warning',
                        'onboarding' => 'success',
                        'active' => 'success',
                        'cold' => 'gray',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'new' => 'New',
                        'initial' => 'Initial',
                        'interested' => 'Interested',
                        'pricing_discussion' => 'Pricing',
                        'ready_to_buy' => 'Ready',
                        'payment_pending' => 'Payment',
                        'onboarding' => 'Onboarding',
                        'active' => 'Active',
                        'cold' => 'Cold',
                        default => $state,
                    })
                    ->sortable(),

                Tables\Columns\TextColumn::make('intent')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'ads' => 'info',
                        'social_management' => 'success',
                        'both' => 'warning',
                        'unclear' => 'gray',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'ads' => 'Ads',
                        'social_management' => 'Social',
                        'both' => 'Both',
                        'unclear' => '?',
                        default => $state,
                    })
                    ->placeholder('—')
                    ->sortable(),

                Tables\Columns\TextColumn::make('lead_level')
                    ->label('Level')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'hot' => 'danger',
                        'warm' => 'warning',
                        'cold' => 'gray',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'hot' => 'Hot',
                        'warm' => 'Warm',
                        'cold' => 'Cold',
                        default => $state,
                    })
                    ->placeholder('—')
                    ->sortable(),

                Tables\Columns\TextColumn::make('selected_plan')
                    ->label('Plan')
                    ->placeholder('—')
                    ->limit(30)
                    ->searchable(),

                Tables\Columns\IconColumn::make('bot_disabled')
                    ->label('Bot')
                    ->boolean()
                    ->trueIcon('heroicon-o-pause-circle')
                    ->falseIcon('heroicon-o-play-circle')
                    ->trueColor('warning')
                    ->falseColor('success'),

                Tables\Columns\TextColumn::make('created_at')
                    ->dateTime('Y-m-d H:i')
                    ->sortable()
                    ->since()
                    ->placeholder('—'),

                Tables\Columns\TextColumn::make('updated_at')
                    ->dateTime('Y-m-d H:i')
                    ->sortable()
                    ->since()
                    ->placeholder('—')
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->defaultSort('updated_at', 'desc')
            ->filters([
                SelectFilter::make('stage')
                    ->options([
                        'new' => 'New',
                        'initial' => 'Initial',
                        'interested' => 'Interested',
                        'pricing_discussion' => 'Pricing',
                        'ready_to_buy' => 'Ready to Buy',
                        'payment_pending' => 'Payment Pending',
                        'onboarding' => 'Onboarding',
                        'active' => 'Active',
                        'cold' => 'Cold',
                    ])
                    ->multiple(),

                SelectFilter::make('lead_level')
                    ->label('Lead Level')
                    ->options([
                        'hot' => 'Hot',
                        'warm' => 'Warm',
                        'cold' => 'Cold',
                    ])
                    ->multiple(),

                SelectFilter::make('intent')
                    ->options([
                        'ads' => 'Ads',
                        'social_management' => 'Social Management',
                        'both' => 'Both',
                        'unclear' => 'Unclear',
                    ])
                    ->multiple(),

                Tables\Filters\TernaryFilter::make('bot_disabled')
                    ->label('Bot Status')
                    ->placeholder('All leads')
                    ->trueLabel('Bot disabled')
                    ->falseLabel('Bot active'),
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
        return [
            //
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListLeads::route('/'),
            'create' => Pages\CreateLead::route('/create'),
            'view' => Pages\ViewLead::route('/{record}'),
            'edit' => Pages\EditLead::route('/{record}/edit'),
        ];
    }

    public static function getNavigationBadge(): ?string
    {
        return static::getModel()::count();
    }
}
