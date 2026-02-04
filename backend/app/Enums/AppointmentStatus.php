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
}
