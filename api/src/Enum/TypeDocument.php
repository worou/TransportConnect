<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.type_document */
enum TypeDocument: string
{
    case CniRecto = 'cni_recto';
    case CniVerso = 'cni_verso';
    case Selfie = 'selfie';
    case RegistreCommerce = 'registre_commerce';
    case Badge = 'badge';
    case Contrat = 'contrat';
}
