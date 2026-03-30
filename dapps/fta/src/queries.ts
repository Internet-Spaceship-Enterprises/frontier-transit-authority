import {
  // Core fetch functions
  executeGraphQLQuery, // Raw GraphQL execution
  getObjectByAddress, // Object with BCS data
  getObjectWithJson, // Object with JSON contents
  getObjectWithDynamicFields, // Object + dynamic fields
  getWalletCharacters,
  parseCharacterFromJson,

  // Assembly + Owner (most useful for EVE)
  getAssemblyWithOwner, // Assembly + character info in one call
  getObjectAndCharacterOwner, // Lower-level version

  // Ownership queries
  getOwnedObjectsByType, // Objects of type owned by address
  getOwnedObjectsByPackage, // Objects from package owned by address

  // Type-based queries
  getObjectsByType, // All objects of a type (paginated)
  getSingletonObjectByType, // First object of a type
  getEveWorldPackageId,
  // Transformation functions
  transformToAssembly,
  GetOwnedObjectsByPackageResponse,
  GET_OWNED_OBJECTS_BY_PACKAGE,
} from "@evefrontier/dapp-kit";

/**
 * STEP 5 (optional) — When useSmartObject isn't enough.
 * getAssemblyWithOwner() for assembly + character;
 * transformToAssembly() for typed Assembly from raw move object.
 * Other helpers: executeGraphQLQuery, getOwnedObjectsByType, getObjectsByType, getSingletonObjectByType.
 */
async function fetchAssemblyInfo(assemblyId: string) {
  // 1. Fetch raw data from GraphQL
  const { moveObject, assemblyOwner } = await getAssemblyWithOwner(assemblyId);

  if (!moveObject) {
    console.error("Assembly not found");
    return null;
  }

  // 2. Access raw JSON data directly
  const rawJson = moveObject.contents.json;
  console.log("Raw assembly data:", rawJson);
  console.log("Assembly owner:", assemblyOwner);

  // 3. Or transform to typed Assembly object
  const assembly = await transformToAssembly(assemblyId, moveObject, {
    character: assemblyOwner,
  });
  console.log("Transformed assembly:", assembly);

  return { assembly, assemblyOwner };
}

/** STEP 5 — getObjectWithJson() for object by ID with JSON. */
async function fetchObjectData(objectId: string) {
  const result = await getObjectWithJson(objectId);

  const json = result.data?.object?.asMoveObject?.contents?.json;
  const type = result.data?.object?.asMoveObject?.contents?.type?.repr;

  console.log("Object type:", type);
  console.log("Object data:", json);

  return json;
}

/** STEP 5 — getOwnedObjectsByType() for owned objects by type and wallet address. */
async function fetchUserAssemblies(
  walletAddress: string,
  assemblyType: string,
) {
  const result = await getOwnedObjectsByType(walletAddress, assemblyType);

  const objectAddresses = result.data?.address?.objects?.nodes.map(
    (node) => node.address,
  );

  console.log("Owned object addresses:", objectAddresses);
  return objectAddresses;
}

async function fetchOwnedObjectsByPackage(
  owner: string,
) {
  const result = await getOwnedObjectsByPackage(owner, getEveWorldPackageId());

  // const objectAddresses = result.data?.address?.objects?.nodes.map(
  //   (node) => node.address,
  // );

  console.log("Owned objects by package:", result.data);
  return null;
}

async function fetchWalletCharacters(
  owner: string,
) {

  const response = await getWalletCharacters(owner);

  const data = response.data;
  if (!data) {
    console.warn("[Dapp] No data returned from getWalletCharacters");
    return;
  }
  const json =
    data?.address?.objects?.nodes?.[0]?.contents?.extract?.asAddress
      ?.asObject?.asMoveObject?.contents?.json;
  const characterInfo = parseCharacterFromJson(json);
  console.log("Wallet characters:", data);
  return characterInfo;
}
export { fetchAssemblyInfo, fetchObjectData, fetchUserAssemblies, fetchOwnedObjectsByPackage, fetchWalletCharacters };
