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