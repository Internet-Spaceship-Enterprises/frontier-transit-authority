export const GET_OBJECT_JSON_BY_ID = `
  query GetObjectJsonById($address: SuiAddress!){
    object(address: $address) {
        asMoveObject {
            contents {
                type {
                    repr
                }
                json
            }
        }
    }
  }`;

export const GET_FTA = `
  query GetFTA($address: SuiAddress!) {
    object(address: $address) {
        asMoveObject {
            contents {
                json
            }
        }
    }
  }
  `;

export const GET_TABLE = `
query GetTable($address: SuiAddress!, $first: Int = 50, $after: String) {
  address(address: $address) {
    addressAt {
      dynamicFields(first: $first, after: $after) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          name {
            type { repr }
            json
          }
          value {
            __typename
            ... on MoveValue {
              type { repr }
              json
            }
            ... on MoveObject {
              address
              contents {
                type { repr }
                json
              }
            }
          }
        }
      }
    }
  }
}`;

export const GET_LOCATION_REGISTRY = `
query GetLocationRegistry($address: SuiAddress!) {
  object(address: $address) {
    asMoveObject {
      contents {
        json
      }
    }
  }
}`;