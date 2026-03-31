import { Text, Flex, Spinner } from "@radix-ui/themes";

export function Loading() {
    return (
        <Flex pt="9" alignSelf="center" justifySelf="center" gap="4">
            <Spinner size="3" />
            <Text>Loading...</Text>
        </Flex>
    );
}