{-# LANGUAGE ScopedTypeVariables #-}
module Handler.Blog where

import Import

import qualified Database.Esqueleto      as E
import           Database.Esqueleto      ((^.))

import Text.Blaze.Html.Renderer.String (renderHtml)

getBlogR :: Int -> Handler Html
getBlogR site = do
                  let postsPerSite = 3
                  let maxTagCloud = 10

                  when (site < 1) $ do
                                      setMessage $ toHtml $ (show site) <> " is no valid site."
                                      redirect $ BlogR 1
                  allPosts <- runDB $ selectList [] [Desc BlogPostDate]
                  let numPosts = length(allPosts)
                  let numPages = if (mod numPosts postsPerSite) > 0
                                   then (quot numPosts postsPerSite) + 1
                                   else quot numPosts postsPerSite
                  when ((site > numPages) && (site /= 1)) $ do
                                                              setMessage $ toHtml $ (show site) <> " is no valid site."
                                                              redirect $ BlogR numPages

                  name <- runDB $ selectFirst [] [Asc BlogNameId]
                  let blogName = case name of
                                   Nothing -> "a FANTASTIC blog (blog name not yet chosen)"
                                   Just (Entity _ (BlogName n)) -> n

                  let previousPage = site-1
                  let nextPage = site+1
                  posts <- runDB $ selectList [] [Desc BlogPostDate, LimitTo postsPerSite, OffsetBy (postsPerSite*(site-1))]
                  comments <- runDB $ selectList [] [Desc CommentDate, LimitTo postsPerSite]
                  let firstPost = postsPerSite*(site-1)+1
                  let lastPost = firstPost+length(posts)-1

                  (tags :: [(E.Value Text, E.Value Int)]) <- runDB
                        $ E.select
                        $ E.from $ \tag -> do
                            E.groupBy $ tag ^. TagTitle
                            let (countRows' :: E.SqlExpr (E.Value Int)) = E.countRows
                            E.orderBy [E.desc countRows']
                            E.limit maxTagCloud
                            return (tag ^. TagTitle, countRows')

                  maid <- maybeAuthId
                  (searchWidget, theEnctype) <- generateFormPost searchForm
                  
                  defaultLayout $ [whamlet|
                    <aside>
                      <h3>Tag Cloud
                      <ul>
                         $forall (E.Value tagTitle, E.Value count) <- tags
                           <li><font size="#{count}"><a href=@{TagR tagTitle 1}> #{tagTitle}: #{count}</a></font>
                      <hr>
                      <form method=post enctype=#{theEnctype}>
                        ^{searchWidget}
                        <button>Search!
                    <h1>Welcome to #{blogName}
                    <table>
                      <tr>
                        <td>
                          $maybe _ <- maid
                            <form method=get action=@{AuthR LogoutR}>
                              <button>Logout
                          $nothing
                            <form method=get action=@{AuthR LoginR}>
                              <button>Login
                        <td>
                          <form method=get action=@{AddPostR}>
                            <button>New Post
                        <td>
                          <form method=get action=@{SettingsR}>
                            <button>Settings
                    <hr>
                    $if null posts
                      <h2>Posts
                      No Posts! :(
                    $else
                      <h2>Posts #{firstPost} - #{lastPost}
                      $forall Entity postId (BlogPost author title text date) <- posts
                        <article class=post>
                          <header>
                            <h3><a href=@{BlogPostR postId}>#{title}</a>
                          #{text}
                          <footer>
                            $maybe _ <- maid
                              <a href=@{BlogPostEditR postId}><img alt="Edit" src=@{StaticR edit_png}></a>
                              <a href=@{BlogPostDeleteR postId}><img alt="Delete" src=@{StaticR delete_png}></a>
                            posted: #{formatTime defaultTimeLocale "%c" date}
                    <hr>
                    <table>
                      <tr>
                        $if (site /= 1)
                          <td>
                            <form method=get action=@{BlogR 1}>
                              <button>First
                          <td>
                            <form method=get action=@{BlogR previousPage}>
                              <button>Previous
                        <td>
                          Page #{site} of #{numPages}
                        $if (site /= numPages)
                          <td>
                            <form method=get action=@{BlogR nextPage}>
                              <button>Next
                          <td>
                            <form method=get action=@{BlogR numPages}>
                              <button>Last
                    <hr>
                    <h2>Last Comments
                    $if null comments
                      No Comments! :(
                    $else
                      $forall Entity _ (Comment bPost author title text date) <- comments
                        <article class=comment>
                          <header>
                            <h3><a href=@{BlogPostR bPost}>#{title}</a>
                          #{text}
                          <footer>
                            commented: #{formatTime defaultTimeLocale "%c" date}
                          
                    <hr>
                  |]

postBlogR :: Int -> Handler Html
postBlogR _ = do
                   ((res,_),_) <- runFormPost searchForm
                   case res of
                     FormSuccess s -> do
                       posts <- runDB $ selectList [] [Desc BlogPostDate]
                       let hitTitle = [ x | x <- posts, (Entity _ (BlogPost _ y _ _)) <- [x], isInfixOf s y]
                       let hitText = [ x | x <- posts, (Entity _ (BlogPost _ _ y _)) <- [x], isInfixOf s (pack $ renderHtml y)]

                       maid <- maybeAuthId
                       defaultLayout $ [whamlet|
                         <h1>Results:
                         <table>
                          <tr>
                            <td>
                              $maybe _ <- maid
                                <form method=get action=@{AuthR LogoutR}>
                                  <button>Logout
                              $nothing
                                <form method=get action=@{AuthR LoginR}>
                                  <button>Login
                            <td>
                              <form method=get action=@{BlogR 1}>
                                <button>Home
                            <td>
                              <form method=get action=@{AddPostR}>
                                <button>New Post
                            <td>
                              <form method=get action=@{SettingsR}>
                                <button>Settings
                         <h2>Caution: Search may not be that cool... e.g. when there are html tags between words<br>and yes... it's case sensitive
                         <h1>Hits in Post Titles:
                         $if null hitTitle
                           No results in titles.
                         $else
                           $forall Entity postId (BlogPost author title text date) <- hitTitle
                             <article class=post>
                               <header>
                                 <h3><a href=@{BlogPostR postId}>#{title}</a>
                               #{text}
                               <footer>
                                 posted #{show date}
                         <h1>Hits in Post Texts:
                         $if null hitText
                           No results in texts.
                         $else
                           $forall Entity postId (BlogPost author title text date) <- hitText
                             <article class=post>
                               <header>
                                 <h3><a href=@{BlogPostR postId}>#{title}</a>
                               #{text}
                               <footer>
                                 posted #{show date}
                         <hr>
                       |]
                     _ -> defaultLayout $ [whamlet|
                       <h1>Sorry, something went wrong!
                         <form method=get action=@{BlogR 1}>
                           <button>Return to main page
                       <hr>
                     |]

searchForm :: Form Text
searchForm = renderDivs $ areq textField "Search a word: " Nothing
