<?php

namespace App\ApiResource\Auth;

final class OtpEnvoye
{
    public function __construct(
        public readonly string $otpId,
        public readonly int $expiresIn,
        /** Uniquement si OTP_DEBUG=1 */
        public readonly ?string $codeDev = null,
    ) {
    }
}
