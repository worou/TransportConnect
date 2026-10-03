<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.canal_notification */
enum CanalNotification: string
{
    case Push = 'push';
    case Sms = 'sms';
    case InApp = 'in_app';
    case Email = 'email';
}
