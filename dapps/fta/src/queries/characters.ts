import {
    // Core fetch functions
    executeGraphQLQuery, // Raw GraphQL execution
    GET_WALLET_CHARACTERS,
    GetWalletCharactersResponse,
    parseCharacterFromJson,
    CharacterInfo,
} from "@evefrontier/dapp-kit";
import { worldOriginalPackageId } from "../utils";

export async function getWalletCharacters(wallet: string): Promise<CharacterInfo[]> {
    const result = await executeGraphQLQuery<GetWalletCharactersResponse>(
        GET_WALLET_CHARACTERS,
        {
            owner: wallet,
            characterPlayerProfileType: `${worldOriginalPackageId()}::character::PlayerProfile`,
        },
    );
    const moveObject = result.data?.address.objects.nodes.map((node) => {
        const characterInfo = parseCharacterFromJson(node.contents.extract.asAddress.asObject.asMoveObject.contents.json);
        if (!characterInfo) {
            console.error("Failed to parse character info for object", node);
            return null;
        }
        return characterInfo;
    })!;
    return moveObject.filter((char) => char !== null && char !== undefined);
}