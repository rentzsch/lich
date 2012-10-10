import Control.Applicative
import Control.Monad
import Data.ByteString (ByteString)
import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as C
import Data.Map (Map)
import qualified Data.Map as M
import Text.Parsec hiding ((<|>), many)
import Text.PrettyPrint.HughesPJ ((<>), brackets, text, braces, hsep)
import qualified Text.PrettyPrint.HughesPJ as P
import Debug.Trace

type Parser = Parsec ByteString ()

type LichData = ByteString

data Lich = Data LichData
          | Array [Lich]
          | Dict (Map LichData Lich)
          deriving (Show)

recurWith :: Parser a -> ByteString -> Parser [a]
recurWith parser s = do
  i <- getInput
  setInput s
  r <- (many parser <* eof)
  setInput i
  return r

parseDocument = (some parseElement) <|> (eof *> pure [])

parseElement = try parseData <|> try parseArray <|> try parseDict

parseData = do
  size <- parseSize
  data' <- between (char '<') (char '>') $ count size anyChar
  return $ Data (C.pack data')

parseArray = do
  size  <- parseSize
  text <- between (char '[') (char ']') $ C.pack <$> count size anyChar
  Array <$> recurWith parseElement text

parseDict = do
  size  <- parseSize
  elems <- between (char '{') (char '}') $ C.pack <$> count size anyChar
  Dict <$> M.fromList <$> recurWith parseKey elems

parseKey :: Parser (LichData, Lich)
parseKey = liftM2 (,) parseDataRaw parseElement
  where parseDataRaw = parseData >>= go
        go (Data s)  = return s
        go x         = unexpected (show x)

parseSize :: Parser Int
parseSize = read <$> (some digit)

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