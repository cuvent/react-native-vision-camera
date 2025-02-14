import type { Point } from './Point'

/**
 * The type of the code to scan.
 */
export type CodeType =
  | 'code-128'
  | 'code-39'
  | 'code-93'
  | 'codabar'
  | 'gs1-data-bar'
  | 'gs1-data-bar-limited'
  | 'gs1-data-bar-expanded'
  | 'ean-13'
  | 'ean-8'
  | 'itf'
  | 'itf-14'
  | 'upc-e'
  | 'upc-a'
  | 'qr'
  | 'pdf-417'
  | 'aztec'
  | 'data-matrix'

/**
 * The full area that is used for code scanning. In most cases, this is 1280x720 or 1920x1080.
 */
export interface CodeScannerFrame {
  /**
   * The width of the frame
   */
  width: number
  /**
   * The height of the frame
   */
  height: number
}

/**
 * A scanned code.
 */
export interface Code {
  /**
   * The type of the code that was scanned.
   */
  type: CodeType | 'unknown'
  /**
   * The string value, or null if it cannot be decoded.
   */
  value?: string
  /**
   * The location of the code relative to the Camera Preview (in dp).
   */
  frame?: {
    x: number
    y: number
    width: number
    height: number
  }
  /**
   * The location of each corner relative to the Camera Preview (in dp).
   */
  corners?: Point[]
}

/**
 * A scanner for detecting codes in a Camera Stream.
 */
export interface CodeScanner {
  /**
   * The types of codes to configure the code scanner for.
   */
  codeTypes: CodeType[]
  /**
   * A callback to call whenever the scanned codes change.
   * @param codes The scanned codes, or an empty array if none.
   * @param frame The full area that is used for scanning. Code bounds and corners are relative to this frame.
   */
  onCodeScanned: (codes: Code[], frame: CodeScannerFrame) => void
  /**
   * Crops the scanner's view area to the specific region of interest.
   *
   * @platform iOS
   */
  regionOfInterest?: {
    x: number
    y: number
    width: number
    height: number
  }
}
