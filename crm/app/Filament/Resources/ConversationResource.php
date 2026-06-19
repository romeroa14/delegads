<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ConversationResource\Pages;
use App\Models\Conversation;
use BackedEnum;
use Filament\Actions;
use Filament\Forms;
use Filament\Resources\Resource;
use Filament\Schemas;
use Filament\Schemas\Schema;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;
use UnitEnum;

class ConversationResource extends Resource
{
    protected static ?string $model = Conversation::class;

    protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-chat-bubble-left-right';

    protected static string|UnitEnum|null $navigationGroup = 'Sales Pipeline';

    protected static ?string $modelLabel = 'Message';

    protected static ?string $pluralModelLabel = 'Messages';

    protected static ?int $navigationSort = 2;

    public static function form(Schema $schema): Schema
    {
        return $schema
            ->schema([
                Schemas\Components\Section::make('Message')
                    ->columns(2)
                    ->schema([
                        Forms\Components\Select::make('tenant_lead_id')
                            ->label('Lead')
                            ->relationship('lead', 'client_name')
                            ->getOptionLabelFromRecordUsing(fn ($record) => $record->client_name
                                ? "{$record->client_name} ({$record->phone_number})"
                                : $record->phone_number)
                            ->searchable(['client_name', 'phone_number'])
                            ->preload()
                            ->required(),

                        Forms\Components\Select::make('direction')
                            ->options([
                                'inbound' => 'Inbound (Client)',
                                'outbound' => 'Outbound (Bot/Agent)',
                            ])
                            ->required()
                            ->native(false),

                        Forms\Components\Select::make('platform')
                            ->options([
                                'whatsapp' => 'WhatsApp',
                                'instagram' => 'Instagram',
                                'messenger' => 'Messenger',
                                'web' => 'Web',
                            ])
                            ->required()
                            ->default('whatsapp')
                            ->native(false),

                        Forms\Components\Select::make('status')
                            ->options([
                                'sent' => 'Sent',
                                'delivered' => 'Delivered',
                                'read' => 'Read',
                                'failed' => 'Failed',
                                'received' => 'Received',
                            ])
                            ->required()
                            ->default('sent')
                            ->native(false),

                        Forms\Components\Toggle::make('is_client_message')
                            ->label('From Client')
                            ->inline(false),

                        Forms\Components\Toggle::make('handled_by_ai')
                            ->label('Handled by AI')
                            ->inline(false),
                    ]),

                Schemas\Components\Section::make('Content')
                    ->schema([
                        Forms\Components\Textarea::make('content')
                            ->required()
                            ->rows(5)
                            ->columnSpanFull(),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->sortable(),

                Tables\Columns\TextColumn::make('lead.client_name')
                    ->label('Client')
                    ->searchable(['lead.client_name', 'lead.phone_number'])
                    ->placeholder('—')
                    ->limit(20),

                Tables\Columns\TextColumn::make('direction')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'inbound' => 'info',
                        'outbound' => 'success',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'inbound' => 'IN',
                        'outbound' => 'OUT',
                        default => $state,
                    })
                    ->icon(fn (string $state): string => match ($state) {
                        'inbound' => 'heroicon-m-arrow-down-left',
                        'outbound' => 'heroicon-m-arrow-up-right',
                        default => '',
                    }),

                Tables\Columns\TextColumn::make('content')
                    ->limit(60)
                    ->wrap()
                    ->searchable(),

                Tables\Columns\TextColumn::make('platform')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'whatsapp' => 'success',
                        'instagram' => 'warning',
                        'messenger' => 'info',
                        'web' => 'gray',
                        default => 'gray',
                    }),

                Tables\Columns\IconColumn::make('handled_by_ai')
                    ->label('AI')
                    ->boolean()
                    ->trueIcon('heroicon-o-cpu-chip')
                    ->falseIcon('heroicon-o-user')
                    ->trueColor('info')
                    ->falseColor('gray'),

                Tables\Columns\TextColumn::make('status')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'sent', 'delivered' => 'success',
                        'read' => 'info',
                        'failed' => 'danger',
                        'received' => 'gray',
                        default => 'gray',
                    }),

                Tables\Columns\TextColumn::make('created_at')
                    ->label('Sent At')
                    ->dateTime('Y-m-d H:i')
                    ->sortable()
                    ->since(),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                SelectFilter::make('direction')
                    ->options([
                        'inbound' => 'Inbound',
                        'outbound' => 'Outbound',
                    ]),

                SelectFilter::make('platform')
                    ->options([
                        'whatsapp' => 'WhatsApp',
                        'instagram' => 'Instagram',
                        'messenger' => 'Messenger',
                        'web' => 'Web',
                    ]),

                TernaryFilter::make('handled_by_ai')
                    ->label('Handled by AI')
                    ->placeholder('All')
                    ->trueLabel('AI only')
                    ->falseLabel('Human only'),
            ])
            ->actions([
                Actions\ViewAction::make(),
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
            'index' => Pages\ListConversations::route('/'),
            'view' => Pages\ViewConversation::route('/{record}'),
        ];
    }
}
