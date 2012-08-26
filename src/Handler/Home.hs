{-# LANGUAGE TupleSections, OverloadedStrings #-}
module Handler.Home (getHomeR
                    , postPomodoroR
                    , postBreakR) where

import Import
import Data.Maybe (fromMaybe, fromJust)
import Data.Text (unpack)
import Data.Time
import DebugUtil
import System.Locale (defaultTimeLocale)
import Yesod.Auth
import qualified Yesod.Auth.OAuth as OA

import Model.Asana

textToUTCTime :: UTCTime -> Text -> UTCTime
textToUTCTime currentTime text =
    fromMaybe currentTime
    $ Data.Time.parseTime defaultTimeLocale "%Y-%m-%dT%H:%M:%S%QZ" $ unpack text

pomodoroForm :: UTCTime -> FormInput App App Pomodoro
pomodoroForm currentTime = Pomodoro
      <$> ireq dayField "startOn"
      <*> (textToUTCTime currentTime) `fmap` ireq textField "startAt"
      <*> (textToUTCTime currentTime) `fmap` ireq textField "endAt"
      <*> ireq textField "taskId"
      <*> ireq textField "taskName"

breakForm :: UTCTime -> FormInput App App Break
breakForm currentTime = Break
      <$> ireq dayField "startOn"
      <*> (textToUTCTime currentTime) `fmap` ireq textField "startAt"
      <*> (textToUTCTime currentTime) `fmap` ireq textField "endAt"

getHomeR :: Handler RepHtml
getHomeR = do
  maid <- maybeAuthId
  case maid of
    Just aid -> do
      mrec <- runDB $ getBy $ UniqueConfigByUserId aid
      case mrec of
        Nothing -> redirect SettingsR -- need to set Asana API key
        Just (Entity _ (AsanaConfig _ _ wks)) -> do
          mworkspace <- lookupSession "workspaceId"
          let workspaces = fmap unpersist wks
              selectedWorkspace = fromMaybe "" mworkspace
          defaultLayout $ do
            setTitle "Pomodoro - Napolitan"
            $(widgetFile "pomodoro-js")
            $(widgetFile "pomodoro")
    Nothing -> defaultLayout $ do
      setTitle "Napolitan = Asana + Pomorodo"
      $(widgetFile "welcome")

postPomodoroR :: Handler RepJson
postPomodoroR = do
  utcTime <- liftIO $ getCurrentTime
  pomodoro <- runInputPost $ pomodoroForm utcTime
  liftIO $ debugLog $ show pomodoro
  _ <- runDB $ insert pomodoro
  jsonToRepJson ()

postBreakR :: Handler RepJson
postBreakR = do
  utcTime <- liftIO $ getCurrentTime
  break <- runInputPost $ breakForm utcTime
  liftIO $ debugLog $ show break
  _ <- runDB $ insert break
  jsonToRepJson ()
