<?php

namespace App\Enums;

enum AppointmentStatus: int
{
    case PendingConfirmation = 1;
    case Confirmed = 2;
    case Attended = 3;
    case Absent = 4;
    case Rejected = 5;
    case Cancelled = 6;

    public function descriptor(): string
    {
        return match ($this) {
            self::PendingConfirmation => 'Por confirmar',
            self::Confirmed => 'Confirmada',
            self::Attended => 'Atendida',
            self::Absent => 'Ausente',
            self::Rejected => 'Rechazada',
            self::Cancelled => 'Cancelada',
        };
    }
}
