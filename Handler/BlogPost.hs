module Handler.BlogPost where

import Import

import Yesod.Form.Nic (YesodNic, nicHtmlField)
instance YesodNic App

getBlogPostR :: BlogPostId -> Handler Html
getBlogPostR bPostId = do
                         bPost <- runDB $ get404 bPostId
                         comments <- runDB $ selectList [CommentBlogpost ==. bPostId] [Desc CommentDate]
                         (commentWidget, theEnctype) <- generateFormPost (commentForm bPostId)
                         defaultLayout $ [whamlet|
                           <h2>Post No. #{toPathPiece bPostId}
                           <table>
                             <tr>
                               <td>
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
                           <h1>#{blogPostTitle bPost}
                           posted: #{show $ blogPostDate bPost}
                           <article class=post>
                             #{blogPostText bPost}
                           <h2>Comments
                           <article class=comment>
                             <form method=post enctype=#{theEnctype}>
                               <h3>Add new comment:
                               <noscript>
                                 <b>To get a nice editor, please enable JavaScript!
                               ^{commentWidget}
                               <button>Submit!
                           $if null comments
                             No comments added yet.
                           $else
                             $forall Entity commentId (Comment bPost title text date) <- comments
                               <article class=comment>
                                 <header>
                                   <h3>#{title}
                                 #{text}
                                 <footer>
                                   posted: #{show date}

                           <hr>
                         |]

postBlogPostR :: BlogPostId -> Handler Html
postBlogPostR bPostId = do
                          ((res,commentWidget),theEnctype) <- runFormPost (commentForm bPostId)
                          case res of
                            FormSuccess comment -> do
                              commentId <- runDB $ insert comment
                              redirect $ BlogPostR bPostId
                            _ -> defaultLayout $ [whamlet|
                            <h1>Sorry, something went wrong!
                            <table>
                               <tr>
                                 <td>
                                   <form method=get><button>Try again
                                 <td>
                                   <form method=get action=@{BlogR 1}><button>Return to main page
                            |]

commentForm :: BlogPostId -> Form Comment
commentForm postId= renderDivs $ Comment
    <$> pure postId
    <*> areq textField "Title: " Nothing
    <*> areq nicHtmlField "Text: " Nothing
    <*> lift (liftIO getCurrentTime)
