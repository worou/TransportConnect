<?php

namespace App\Entity;

use ApiPlatform\Doctrine\Orm\Filter\IriFilter;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\QueryParameter;
use App\Enum\StatutDemande;
use Doctrine\ORM\Mapping as ORM;

/** Timeline de suivi d'une demande, alimentée par un trigger : lecture seule. */
#[ORM\Entity(readOnly: true)]
#[ORM\Table(name: 'historique_statut', schema: 'transconnect')]
#[ApiResource(
    operations: [
        new GetCollection(parameters: ['demande' => new QueryParameter(filter: new IriFilter(), property: 'demande')]),
        new Get(),
    ],
    order: ['id' => 'ASC'],
)]
class HistoriqueStatut
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_historique', type: 'bigint')]
    #[ORM\GeneratedValue(strategy: 'IDENTITY')]
    public ?int $id = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_demande', referencedColumnName: 'id_demande', nullable: false, onDelete: 'CASCADE')]
    public Demande $demande;

    #[ORM\Column(type: 'string', nullable: true, enumType: StatutDemande::class)]
    public ?StatutDemande $ancienStatut = null;

    #[ORM\Column(type: 'string', enumType: StatutDemande::class)]
    public StatutDemande $nouveauStatut;

    #[ORM\Column(type: 'datetimetz_immutable')]
    public \DateTimeImmutable $dateChangement;
}
