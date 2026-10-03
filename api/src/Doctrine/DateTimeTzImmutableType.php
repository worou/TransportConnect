<?php

namespace App\Doctrine;

use Doctrine\DBAL\Platforms\AbstractPlatform;
use Doctrine\DBAL\Types\DateTimeTzImmutableType as BaseType;

/**
 * Les colonnes TIMESTAMPTZ remplies par PostgreSQL (DEFAULT now()) contiennent des microsecondes
 * ("2026-10-03 11:21:43.42999+02"), que le type DBAL standard (format Y-m-d H:i:sO) refuse.
 */
final class DateTimeTzImmutableType extends BaseType
{
    public function convertToPHPValue(mixed $value, AbstractPlatform $platform): ?\DateTimeImmutable
    {
        if (\is_string($value)) {
            $date = \DateTimeImmutable::createFromFormat('Y-m-d H:i:s.uP', $value)
                ?: \DateTimeImmutable::createFromFormat('Y-m-d H:i:sP', $value);
            if (false !== $date) {
                return $date;
            }
        }

        return parent::convertToPHPValue($value, $platform);
    }
}
