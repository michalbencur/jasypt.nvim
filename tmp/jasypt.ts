'use strict';
import { createCipheriv, createDecipheriv, pbkdf2Sync, randomBytes } from 'crypto';

/**
 * Creates an encryptor compatible with Java's Jasypt implementation as used by MyBMW,
 * using PBEWITHHMACSHA512ANDAES_256 with 1000 iterations.
 * @param secretKey encryption key, e.g., process.env.JASYPT_ENCRYPTOR_PASSWORD
 */
export const createJasypt = (secretKey: string = process.env.JASYPT_ENCRYPTOR_PASSWORD as string) => {
    const cipherName = 'aes-256-cbc';
    const hashAlgorithm = 'sha512';
    const iterations = 1000;
    const saltStart = 0;
    const saltSizeBytes = 16;
    const keyBytes = 32;

    const createIV = (salt: Buffer) => {
        const kiv = pbkdf2Sync(secretKey, salt, iterations, 64, hashAlgorithm);
        const keybuf = kiv.subarray(0, keyBytes);
        const ivbuf = kiv.subarray(keyBytes, keyBytes + 16);
        return [keybuf, ivbuf];
    };

    /**
     * Encrypts text.
     * @param text text to encrypt, utf-8 encoding
     * @returns Base64 encoded string
     */
    const encrypt = (text: string) => {
        const salt = randomBytes(saltSizeBytes);
        const buffer = Buffer.concat([salt, Buffer.from(text, 'utf-8')]);
        const [keybuf, ivbuf] = createIV(salt);
        const cipher = createCipheriv(cipherName, keybuf, ivbuf);
        const result = cipher.update(buffer);
        const finalResult = cipher.final();
        return Buffer.concat([salt, result, finalResult]).toString('base64');
    };

    /**
     * Decrypts text.
     * @param encryptedText text to decrypt, string in base64 format
     * @returns a decrypted text in utf-8 format
     */
    const decrypt = (encryptedText: string) => {
        const encryptedBuffer = Buffer.from(encryptedText, 'base64');

        const saltSize = Math.min(saltSizeBytes, encryptedBuffer.length);
        const encMesKernelStart = Math.min(saltSizeBytes, encryptedBuffer.length);
        const encMesKernelSize = Math.max(encryptedBuffer.length - saltSizeBytes, 0);

        const salt = Buffer.alloc(saltSize);
        const encryptedMessageKernel = Buffer.alloc(encMesKernelSize);
        encryptedBuffer.copy(salt, 0, saltStart, saltSize);
        encryptedBuffer.copy(encryptedMessageKernel, 0, encMesKernelStart, encryptedBuffer.length);

        const [keybuf, ivbuf] = createIV(salt);
        const decipher = createDecipheriv(cipherName, keybuf, ivbuf);
        const decrypted = [];
        decrypted.push(decipher.update(encryptedMessageKernel));
        decrypted.push(decipher.final());
        return Buffer.concat(decrypted).subarray(saltSizeBytes).toString();
    };

    /* eslint-disable @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-member-access */
    const decryptObject = (obj: object) => {
        for (const key in obj) {
            if (!obj.hasOwnProperty(key)) {
                continue;
            }
            const value = (obj as any)[key];
            if (typeof value === 'object') {
                decryptObject(value as object);
            } else if (typeof value === 'string') {
                if (value.indexOf('ENC(') === 0 && value.lastIndexOf(')') === value.length - 1) {
                    const encrypted = value.substring(4, value.length - 1);
                    (obj as any)[key] = decrypt(encrypted);
                }
            } else if (Array.isArray(value)) {
                for (const item of value) {
                    if (typeof item === 'object') {
                        decryptObject(item as object);
                    }
                }
            }
        }
    };

    return {
        encrypt,
        decrypt,
        decryptObject,
    };
};
