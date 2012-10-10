import Control.Applicative
import Control.Monad
import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as C
import qualified Data.Map as M
import Text.Parsec hiding ((<|>), many)
import qualified Text.PrettyPrint.HughesPJ as P

type Parser = Parsec B.ByteString ()

type LichData = B.ByteString

data Lich = Data LichData
          | Array [Lich]
          | Dict (M.Map LichData Lich)
          deriving (Show)

parseDocument = (many1 parseElement) <|> (eof *> pure [])

parseElement = try parseData <|> try parseArray <|> try parseDict

parseData = do
  size <- parseSize
  data' <- char '<' *> count size anyChar <* char '>'
  return $ Data (C.pack data')

parseArray = do
  size  <- parseSize
  char '['
  lookAhead $ count size anyChar
  elems <- many parseElement
  char ']'
  return (Array elems)

parseDict = do
  size  <- parseSize
  char '{'
  lookAhead $ count size anyChar
  elems <- many parseKey
  char '}'
  return (Dict $ M.fromList elems)

parseKey :: Parser (LichData, Lich)
parseKey = liftM2 (,) parseDataRaw parseElement
  where parseDataRaw = parseData >>= go
        go (Data s)  = return s
        go x         = unexpected (show x)

parseSize :: Parser Int
parseSize = read <$> (many1 digit)

lichTest :: String -> IO ()
lichTest s = parseTest parseDocument $ C.pack s


encodeLich :: Lich -> B.ByteString
encodeLich = C.pack . show . prettyLich

prettyLich :: Lich -> P.Doc
prettyLich (Data d) = P.int (B.length d) <> angleBrackets (text $ C.unpack d)
  
prettyLich (Array xs)      = docLength contents <> brackets contents
            where contents = hsep (fmap prettyLich xs)
          
prettyLich (Dict m)         = docLength contents <> braces contents
            where contents  = hsep $ fmap go (M.toList m)
                  go (k, v) = prettyLich (Data k) <> prettyLich v

docLength = P.int . length . P.render
angleBrackets d = P.char '<' <> d <> P.char '>'

(<>) = (P.<>)
brackets = P.brackets
text = P.text
braces = P.braces
hsep = P.hsep