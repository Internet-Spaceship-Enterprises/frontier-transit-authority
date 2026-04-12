type Location = {
    x: number;
    y: number;
    z: number;
};

type GateDestination = {
    constellationId: number;
    id: number;
    location: Location;
    name: string;
    regionId: number;
};

type GateLink = {
    destination: GateDestination;
    id: number;
    location: Location;
    name: string;
};

export type SolarSystemResponse = {
    constellationId: number;
    gateLinks: GateLink[];
    id: number;
    location: Location;
    name: string;
    regionId: number;
};

export async function getSolarSystem(
    solarSystemId: number | string,
): Promise<SolarSystemResponse> {
    const url =
        `https://world-api-utopia.uat.pub.evefrontier.com/v2/solarsystems/` +
        `${encodeURIComponent(String(solarSystemId))}?format=json`;

    const response = await fetch(url, {
        method: "GET",
        headers: {
            Accept: "application/json",
        },
    });

    if (!response.ok) {
        throw new Error(
            `Failed to fetch solar system ${solarSystemId}: ` +
            `${response.status} ${response.statusText}`,
        );
    }

    const data = (await response.json()) as SolarSystemResponse;
    return data;
}