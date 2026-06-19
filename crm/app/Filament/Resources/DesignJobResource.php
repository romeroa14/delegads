<?php

namespace App\Filament\Resources;

use App\Filament\Resources\DesignJobResource\Pages;
use App\Models\DesignJob;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Filters\SelectFilter;

class DesignJobResource extends Resource
{
    protected static ?string $model = DesignJob::class;

    protected static ?string $navigationIcon = 'heroicon-o-paint-brush';

    protected static ?string $navigationGroup = 'Design Operations';

    protected static ?string $modelLabel = 'Design Job';

    protected static ?string $pluralModelLabel = 'Design Jobs';

    protected static ?int $navigationSort = 1;

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Request')
                    ->columns(2)
                    ->schema([
                        Forms\Components\Select::make('lead_id')
                            ->label('Lead')
                            ->relationship('lead', 'client_name')
                            ->getOptionLabelFromRecordUsing(fn ($record) => $record->client_name
                                ? "{$record->client_name} ({$record->phone_number})"
                                : $record->phone_number)
                            ->searchable(['client_name', 'phone_number'])
                            ->preload()
                            ->columnSpan(1),

                        Forms\Components\Select::make('type')
                            ->options([
                                'ai_generated' => 'AI Generated',
                                'human_designer' => 'Human Designer',
                            ])
                            ->required()
                            ->default('ai_generated')
                            ->native(false)
                            ->columnSpan(1),

                        Forms\Components\Select::make('status')
                            ->options([
                                'requested' => 'Requested',
                                'in_progress' => 'In Progress',
                                'review' => 'Review',
                                'approved' => 'Approved',
                                'rejected' => 'Rejected',
                                'fallback_ai' => 'Fallback AI',
                            ])
                            ->required()
                            ->default('requested')
                            ->native(false)
                            ->columnSpan(1),

                        Forms\Components\TextInput::make('price')
                            ->numeric()
                            ->prefix('$')
                            ->step(0.01)
                            ->default(5.00)
                            ->columnSpan(1),
                    ]),

                Forms\Components\Section::make('Content')
                    ->columns(1)
                    ->schema([
                        Forms\Components\Textarea::make('prompt')
                            ->label('Design Prompt')
                            ->required()
                            ->rows(4)
                            ->columnSpanFull(),

                        Forms\Components\TextInput::make('result_url')
                            ->label('Result URL')
                            ->url()
                            ->maxLength(65535)
                            ->columnSpanFull(),
                    ]),

                Forms\Components\Section::make('Designer Assignment')
                    ->columns(2)
                    ->schema([
                        Forms\Components\Select::make('designer_id')
                            ->label('Designer')
                            ->relationship('designer', 'name')
                            ->searchable()
                            ->preload()
                            ->columnSpan(1),

                        Forms\Components\Textarea::make('rejected_reason')
                            ->label('Rejection Reason')
                            ->rows(2)
                            ->visible(fn ($get) => $get('status') === 'rejected')
                            ->columnSpan(1),
                    ]),

                Forms\Components\Section::make('Timestamps')
                    ->columns(3)
                    ->collapsed()
                    ->schema([
                        Forms\Components\DateTimePicker::make('created_at')
                            ->disabled()
                            ->dehydrated(false),

                        Forms\Components\DateTimePicker::make('updated_at')
                            ->disabled()
                            ->dehydrated(false),

                        Forms\Components\DateTimePicker::make('fallback_at')
                            ->label('AI Fallback At')
                            ->disabled()
                            ->dehydrated(false),

                        Forms\Components\DateTimePicker::make('approved_at')
                            ->label('Approved At')
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
                    ->sortable(),

                Tables\Columns\TextColumn::make('lead.client_name')
                    ->label('Client')
                    ->searchable(['lead.client_name', 'lead.phone_number'])
                    ->placeholder('—')
                    ->limit(25),

                Tables\Columns\TextColumn::make('type')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'ai_generated' => 'info',
                        'human_designer' => 'success',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'ai_generated' => 'AI',
                        'human_designer' => 'Human',
                        default => $state,
                    }),

                Tables\Columns\TextColumn::make('status')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'requested' => 'gray',
                        'in_progress' => 'info',
                        'review' => 'warning',
                        'approved' => 'success',
                        'rejected' => 'danger',
                        'fallback_ai' => 'warning',
                        default => 'gray',
                    }),

                Tables\Columns\TextColumn::make('prompt')
                    ->label('Prompt')
                    ->limit(50)
                    ->wrap()
                    ->searchable()
                    ->placeholder('—'),

                Tables\Columns\TextColumn::make('designer.name')
                    ->label('Designer')
                    ->placeholder('—')
                    ->toggleable(),

                Tables\Columns\TextColumn::make('price')
                    ->money('USD')
                    ->sortable(),

                Tables\Columns\TextColumn::make('created_at')
                    ->dateTime('Y-m-d H:i')
                    ->sortable()
                    ->since(),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                SelectFilter::make('type')
                    ->options([
                        'ai_generated' => 'AI Generated',
                        'human_designer' => 'Human Designer',
                    ]),

                SelectFilter::make('status')
                    ->options([
                        'requested' => 'Requested',
                        'in_progress' => 'In Progress',
                        'review' => 'Review',
                        'approved' => 'Approved',
                        'rejected' => 'Rejected',
                        'fallback_ai' => 'Fallback AI',
                    ])
                    ->multiple(),

                SelectFilter::make('designer_id')
                    ->label('Designer')
                    ->relationship('designer', 'name')
                    ->searchable()
                    ->preload(),
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
            'index' => Pages\ListDesignJobs::route('/'),
            'create' => Pages\CreateDesignJob::route('/create'),
            'view' => Pages\ViewDesignJob::route('/{record}'),
            'edit' => Pages\EditDesignJob::route('/{record}/edit'),
        ];
    }

    public static function getNavigationBadge(): ?string
    {
        return static::getModel()::whereIn('status', ['requested', 'in_progress'])->count() ?: null;
    }
}
