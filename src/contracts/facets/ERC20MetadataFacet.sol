// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibERC20Storage.sol";

/**
 * @title ERC20MetadataFacet
 * @notice Provides onchain metadata with embedded SVG logo for the ERC20 token
 * @dev Returns ERC721-style metadata JSON with base64-encoded SVG image
 */
contract ERC20MetadataFacet {
    
    /**
     * @notice Returns token metadata as a JSON string with embedded SVG logo
     * @return JSON metadata string with onchain SVG image
     */
    function tokenURI() external view returns (string memory) {
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20();
        
        // Create SVG logo (a diamond shape with gradient)
        string memory svg = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="200" height="200">',
            '<defs>',
            '<linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">',
            '<stop offset="0%" style="stop-color:#667eea;stop-opacity:1" />',
            '<stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" />',
            '</linearGradient>',
            '</defs>',
            '<rect width="200" height="200" fill="#1a1a2e" rx="20"/>',
            '<polygon points="100,40 160,100 100,160 40,100" fill="url(#grad)" stroke="#ffffff" stroke-width="2"/>',
            '<polygon points="100,40 160,100 100,100" fill="#ffffff" opacity="0.3"/>',
            '<polygon points="40,100 100,100 100,160" fill="#000000" opacity="0.2"/>',
            '<text x="100" y="185" font-family="Arial, sans-serif" font-size="16" font-weight="bold" fill="#ffffff" text-anchor="middle">',
            es.symbol,
            '</text>',
            '</svg>'
        ));

        // Base64 encode the SVG
        string memory base64Svg = _base64Encode(bytes(svg));
        
        // Create the metadata JSON
        string memory json = string(abi.encodePacked(
            '{',
            '"name":"', es.name, '",',
            '"description":"An upgraded ERC20 Diamond token with onchain logo and metadata. Built using the Diamond Standard (EIP-2535) for maximum upgradeability and modularity.",',
            '"image":"data:image/svg+xml;base64,', base64Svg, '",',
            '"attributes":[',
            '{"trait_type":"Token Type","value":"ERC20 Diamond"},',
            '{"trait_type":"Standard","value":"EIP-2535"},',
            '{"trait_type":"Symbol","value":"', es.symbol, '"},',
            '{"trait_type":"Decimals","value":"18"}',
            ']',
            '}'
        ));

        return json;
    }

    /**
     * @notice Base64 encoding function
     * @param data Bytes to encode
     * @return Base64 encoded string
     */
    function _base64Encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";

        // Base64 table
        string memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        
        uint256 encodedLen = 4 * ((data.length + 2) / 3);
        string memory result = new string(encodedLen);

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            for {} lt(dataPtr, endPtr) {} {
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1)
            }

            // Padding
            switch mod(mload(data), 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }
        }

        return result;
    }

    /**
     * @notice Get token name (convenience function)
     * @return Token name
     */
    function getTokenName() external view returns (string memory) {
        return LibERC20Storage.erc20().name;
    }

    /**
     * @notice Get token symbol (convenience function)
     * @return Token symbol
     */
    function getTokenSymbol() external view returns (string memory) {
        return LibERC20Storage.erc20().symbol;
    }
}
